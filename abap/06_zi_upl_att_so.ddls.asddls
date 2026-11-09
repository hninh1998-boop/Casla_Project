@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Int. View - Upload Attachment SO'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_UPL_ATT_SO
  as select from ztb_upl_att_so
  association [0..1] to ZVH_STA_UPL_ATT as _StatusText on $projection.Status = _StatusText.Status
  association [0..1] to ZVH_RES_UPL_ATT as _ResultText on $projection.PostResult = _ResultText.PostResult
{
  key uuid                    as Uuid,

      file_name               as FileName,

      @Semantics.largeObject: {
        mimeType: 'MimeType',
        fileName: 'FileName',
        contentDispositionPreference: #ATTACHMENT
      }
      attachment              as Attachment,

      @Semantics.mimeType: true
      mime_type               as MimeType,

      sales_order             as SalesOrder,
      description             as Description,
      file_size               as FileSize,
      file_size_text          as FileSizeText,

      @ObjectModel.text.element: ['StatusText']
      status                  as Status,
      case status
        when 'E' then 1
        when 'R' then 3
        else 0
      end                     as StatusCriticality,
      @Semantics.text: true
      _StatusText.Description as StatusText,

      @ObjectModel.text.element: ['ResultText']
      post_result             as PostResult,
      case post_result
        when 'E' then 1
        when 'P' then 2
        when 'S' then 3
        else 0
      end                     as ResultCriticality,
      @Semantics.text: true
      _ResultText.Description as ResultText,

      message                 as Message,
      att_doc_number          as AttDocNumber,
      posted_by               as PostedBy,
      posted_at               as PostedAt,

      @Semantics.user.createdBy: true
      created_by              as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at              as CreatedAt,
      @Semantics.user.localInstanceLastChangedBy: true
      local_last_changed_by   as LastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at   as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at         as LastChangedAt,

      _StatusText,
      _ResultText
}
