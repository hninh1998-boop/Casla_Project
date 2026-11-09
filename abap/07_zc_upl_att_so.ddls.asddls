@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Cons. View - Upload Attachment SO'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['FileName']
define root view entity ZC_UPL_ATT_SO
  provider contract transactional_query
  as projection on ZI_UPL_ATT_SO
{
  key Uuid,

      FileName,

      @Semantics.largeObject: {
        mimeType: 'MimeType',
        fileName: 'FileName',
        contentDispositionPreference: #ATTACHMENT
      }
      Attachment,

      @Semantics.mimeType: true
      MimeType,

      SalesOrder,
      Description,
      FileSize,
      FileSizeText,

      @ObjectModel.text.element: ['StatusText']
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVH_STA_UPL_ATT', element: 'Status' } }]
      Status,
      StatusCriticality,
      @Semantics.text: true
      StatusText,

      @ObjectModel.text.element: ['ResultText']
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVH_RES_UPL_ATT', element: 'PostResult' } }]
      PostResult,
      ResultCriticality,
      @Semantics.text: true
      ResultText,

      Message,
      AttDocNumber,
      PostedBy,
      PostedAt,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LocalLastChangedAt,
      LastChangedAt
}
