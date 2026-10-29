@EndUserText.label: 'Abs.Ent. - Sales V3 Export Result'
define abstract entity zabs_sales_v3_result
{
  MimeType      : abap.string(0);
  FileName      : abap.string(0);
  FileContent   : abap.string(0); // base64
  FileExtension : abap.string(0);
}
