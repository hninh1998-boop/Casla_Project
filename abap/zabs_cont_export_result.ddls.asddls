@EndUserText.label: 'Abstract Entity - Cont Export Result'
define abstract entity zabs_cont_export_result
{
  MimeType      : abap.string(0);
  FileName      : abap.string(0);
  FileContent   : abap.string(0); // base64
  FileExtension : abap.string(0);
}
